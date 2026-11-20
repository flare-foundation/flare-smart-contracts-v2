// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { ForbiddenAddressList } from "../../../../contracts/compliance/implementation/ForbiddenAddressList.sol";
import { ForbiddenAddressListProxy } from "../../../../contracts/compliance/proxy/ForbiddenAddressListProxy.sol";
import { IForbiddenAddressList } from "../../../../contracts/userInterfaces/IForbiddenAddressList.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IExternalNetwork } from "../../../../contracts/userInterfaces/IExternalNetwork.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/// A provider that derives a Personal Account from the owner, deterministically.
contract DerivingProvider {
    function getPersonalAccount(string calldata _owner) external pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(_owner)))));
    }
}

/// Providers that fail: either refuses the addition.
contract RevertingProvider {
    function getPersonalAccount(string calldata) external pure returns (address) {
        revert("no account");
    }
}

contract ZeroProvider {
    function getPersonalAccount(string calldata) external pure returns (address) {
        return address(0);
    }
}

/// The list deployed on Mainnet, with one maintainer, and the helpers every ForbiddenAddressList test uses.
abstract contract ForbiddenAddressListTestBase is Test {

    uint256 internal constant TIMELOCK = 3600;
    bytes32 internal constant SRC = bytes32("BTC");
    bytes32 internal constant OTHER_SRC = bytes32("XRP");
    // valid addresses (the validator tests' vectors), each in its canonical form
    string internal constant BTC_A = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4";
    string internal constant BTC_B = "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH";
    string internal constant BTC_C = "3CNHUhP3uyB9EUtRLsmvFUmvGdjGdkTxJw";
    string internal constant BTC_D = "bc1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvses5wp4dt";
    string internal constant BTC_TESTNET = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
    string internal constant XRP_C = "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf";
    string internal constant XRP_X_ADDRESS = "XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXb";
    string internal constant BTC_REGTEST = "bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080";
    address internal constant EVM_A = 0x8589427373D6D84E98730D7795D8f6f8731FDA16;
    address internal constant EVM_B = 0x098B716B8Aaf21512996dC57EB0615e2383E2f96;
    address internal constant EVM_C = 0xA7e5d5A720f06526557c513402f2e6B5fA20b008;

    ForbiddenAddressList internal list;
    address internal governance;
    address internal productionGovernance;
    address internal executor;
    address internal maintainer;
    IGovernanceSettings internal governanceSettings;

    function setUp() public {
        vm.warp(1_700_000_000);
        governance = makeAddr("governance");
        productionGovernance = makeAddr("productionGovernance");
        executor = makeAddr("executor");
        maintainer = makeAddr("maintainer");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        list = _deployList(IExternalNetwork.Network.Mainnet);
        vm.prank(governance);
        list.addMaintainers(_maintainers(maintainer));
    }

    // ------------------------------------------------------------ helpers

    function _switchToProduction() internal {
        vm.prank(governance);
        list.switchToProductionMode();
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(productionGovernance)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getTimelock.selector),
            abi.encode(TIMELOCK)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, executor),
            abi.encode(true)
        );
    }

    function _maintainers(address _a) internal pure returns (address[] memory _addresses) {
        _addresses = new address[](1);
        _addresses[0] = _a;
    }

    function _deployList(IExternalNetwork.Network _network) internal returns (ForbiddenAddressList _list) {
        ForbiddenAddressList implementation = new ForbiddenAddressList();
        _list = ForbiddenAddressList(address(new ForbiddenAddressListProxy(
            governanceSettings, governance, makeAddr("addressUpdater"), _network, address(implementation)
        )));
    }

    function _setProvider(bytes32 _sourceId, address _provider) internal {
        vm.prank(governance);
        list.setPersonalAccountProvider(_sourceId, _provider);
    }

    /// The Personal Account `DerivingProvider` derives for `_owner`.
    function _pa(string memory _owner) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(_owner)))));
    }

    function _expectAddRefused(bytes32 _sourceId, string memory _address) internal {
        vm.prank(maintainer);
        vm.expectRevert(
            abi.encodeWithSelector(IForbiddenAddressList.NonCanonicalAddress.selector, _sourceId, _address)
        );
        list.addForbiddenAddresses(_sourceId, _list(_address));
    }

    function _evm(address _a) internal pure returns (address[] memory _addresses) {
        _addresses = new address[](1);
        _addresses[0] = _a;
    }

    function _evm(address _a, address _b) internal pure returns (address[] memory _addresses) {
        _addresses = new address[](2);
        _addresses[0] = _a;
        _addresses[1] = _b;
    }

    function _evm(address _a, address _b, address _c) internal pure returns (address[] memory _addresses) {
        _addresses = new address[](3);
        _addresses[0] = _a;
        _addresses[1] = _b;
        _addresses[2] = _c;
    }

    function _list(string memory _a) internal pure returns (string[] memory _addresses) {
        _addresses = new string[](1);
        _addresses[0] = _a;
    }

    function _list(string memory _a, string memory _b) internal pure returns (string[] memory _addresses) {
        _addresses = new string[](2);
        _addresses[0] = _a;
        _addresses[1] = _b;
    }

    function _list(
        string memory _a,
        string memory _b,
        string memory _c
    )
        internal pure
        returns (string[] memory _addresses)
    {
        _addresses = new string[](3);
        _addresses[0] = _a;
        _addresses[1] = _b;
        _addresses[2] = _c;
    }

    function _list(
        string memory _a,
        string memory _b,
        string memory _c,
        string memory _d
    )
        internal pure
        returns (string[] memory _addresses)
    {
        _addresses = new string[](4);
        _addresses[0] = _a;
        _addresses[1] = _b;
        _addresses[2] = _c;
        _addresses[3] = _d;
    }
}

contract ForbiddenAddressListTest is ForbiddenAddressListTestBase {

    // ------------------------------------------------------------ adding

    function testMaintainerAddsAddresses() public {
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenAddressAdded(SRC, BTC_A);
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenAddressAdded(SRC, BTC_C);
        vm.expectEmit();
        emit IForbiddenAddressList.ListVersionChanged(SRC, 1);
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_C));

        assertTrue(list.isForbidden(SRC, BTC_A));
        assertTrue(list.isForbiddenHash(SRC, keccak256(bytes(BTC_C))));
        assertFalse(list.isForbidden(SRC, BTC_B));
        assertEq(list.lastAdditionTimestamp(SRC), block.timestamp);
        (bytes32[] memory hashes, uint256 total, uint64 version) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(total, 2);
        assertEq(version, 1);
        assertEq(hashes.length, 2);
        assertEq(hashes[0], keccak256(bytes(BTC_A)));
        assertEq(hashes[1], keccak256(bytes(BTC_C)));
    }

    function testGovernanceAddsAddresses() public {
        vm.prank(governance);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertTrue(list.isForbidden(SRC, BTC_A));
    }

    /// Adding is immediate for governance even in production mode: it freezes value and moves none.
    function testGovernanceAddsAtOnceInProduction() public {
        _switchToProduction();
        vm.prank(productionGovernance);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertTrue(list.isForbidden(SRC, BTC_A));
    }

    /// A batch that only repeats listed addresses changes nothing: no version, no new addition time.
    function testRepeatedAddressesAreSkipped() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B));
        uint64 addedAt = list.lastAdditionTimestamp(SRC);
        skip(1 days);
        vm.recordLogs();
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_B, BTC_A));
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(list.lastAdditionTimestamp(SRC), addedAt);
        (, uint256 total, uint64 version) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(total, 2);
        assertEq(version, 1);
    }

    /// An addition is refused unless every address is in its chain's canonical form on the deployment's network
    /// (here mainnet): the batch reverts at the first that is not, naming it, and nothing of it is added.
    function testAddRevertNonCanonicalAddress() public {
        _expectAddRefused(SRC, "");
        _expectAddRefused(SRC, "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4");      // BIP-173's uppercase
        _expectAddRefused(SRC, "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5");      // a typo: the checksum fails
        _expectAddRefused(SRC, BTC_TESTNET);                                        // another network
        _expectAddRefused(SRC, XRP_C);                                              // another chain
        _expectAddRefused(OTHER_SRC, XRP_X_ADDRESS);                               // the same account, X-address
        // a canonical address before the refused one is not added either: the whole batch reverts
        vm.prank(maintainer);
        vm.expectRevert(abi.encodeWithSelector(IForbiddenAddressList.NonCanonicalAddress.selector, SRC, BTC_TESTNET));
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_TESTNET));
        assertEq(list.getVersion(SRC), 0, "nothing was added");
    }

    /// A source id the list holds no string list under fails every per-source call, reads included: a consumer or
    /// verifier configured with a wrong id must not read an empty list as clean.
    function testPerSourceCallsRevertUnsupportedSourceId() public {
        bytes32[6] memory unsupported = [
            bytes32("testBTC"),     // a test network's id on a mainnet deployment
            bytes32("testXRP"),
            bytes32("ETH"),         // an EVM chain: by address, on the EVM list
            bytes32("LTC"),         // a chain the list has no rule for
            bytes32("DOGE"),        // nor Dogecoin
            bytes32(0)
        ];
        for (uint256 i = 0; i < unsupported.length; i++) {
            bytes32 sourceId = unsupported[i];
            bytes memory refusal =
                abi.encodeWithSelector(IForbiddenAddressList.UnsupportedSourceId.selector, sourceId);
            vm.prank(maintainer);
            vm.expectRevert(refusal);
            list.addForbiddenAddresses(sourceId, _list(BTC_A));
            vm.prank(governance);
            vm.expectRevert(refusal);
            list.removeForbiddenAddresses(sourceId, _list(BTC_A));
            vm.expectRevert(refusal);
            list.isForbiddenHash(sourceId, keccak256(bytes(BTC_A)));
            vm.expectRevert(refusal);
            list.isForbidden(sourceId, BTC_A);
            vm.expectRevert(refusal);
            list.isCanonicalAddress(sourceId, BTC_A);
            vm.expectRevert(refusal);
            list.getForbiddenAddressHashes(sourceId, 0, 10);
            vm.expectRevert(refusal);
            list.getForbiddenAddresses(sourceId, 0, 10);
            vm.expectRevert(refusal);
            list.getVersion(sourceId);
            vm.expectRevert(refusal);
            list.lastAdditionTimestamp(sourceId);
        }
    }

    function testAddRevertOnlyMaintainerOrImmediateGovernance() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IForbiddenAddressList.OnlyMaintainerOrImmediateGovernance.selector);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
    }

    /// Each source has its own list, version and last-addition time.
    function testListsArePerSource() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(OTHER_SRC, _list(XRP_C));
        skip(1 hours);
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B));
        assertTrue(list.isForbidden(OTHER_SRC, XRP_C));
        assertTrue(list.isForbidden(SRC, BTC_A));
        assertFalse(list.isForbidden(OTHER_SRC, "rhbQ2PoSsmzh5XnmWnutCa6dmAC2qj1z1S"), "listed under no source");
        assertEq(list.lastAdditionTimestamp(OTHER_SRC), block.timestamp - 1 hours);
        assertEq(list.lastAdditionTimestamp(SRC), block.timestamp);
        (, uint256 total, uint64 version) = list.getForbiddenAddressHashes(OTHER_SRC, 0, 10);
        (, uint256 btcTotal, uint64 btcVersion) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(total, 1);
        assertEq(btcTotal, 2);
        assertEq(version, 1);
        assertEq(btcVersion, 1);
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_A));
        assertTrue(list.isForbidden(OTHER_SRC, XRP_C), "a removal under one source leaves the others");
        assertEq(list.getVersion(OTHER_SRC), 1);
        assertEq(list.getVersion(SRC), 2);
    }

    /// The version getter follows every change, per source; calls that change nothing leave it.
    function testGetVersion() public {
        assertEq(list.getVersion(SRC), 0);
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B));
        assertEq(list.getVersion(SRC), 1);
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertEq(list.getVersion(SRC), 1, "a repeated batch changes nothing");
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_A));
        assertEq(list.getVersion(SRC), 2);
        assertEq(list.getVersion(OTHER_SRC), 0, "another source is untouched");
        (, , uint64 paged) = list.getForbiddenAddressHashes(SRC, 0, 0);
        assertEq(paged, list.getVersion(SRC));
    }

    /// The canonical form on a mainnet deployment: what can be listed and checked by string.
    function testIsCanonicalAddress() public view {
        assertEq(uint256(list.getNetwork()), uint256(IExternalNetwork.Network.Mainnet));
        assertTrue(list.isCanonicalAddress(SRC, BTC_A));
        assertTrue(list.isCanonicalAddress(SRC, BTC_B));
        assertTrue(list.isCanonicalAddress(SRC, BTC_C));
        assertTrue(list.isCanonicalAddress(SRC, BTC_D));
        assertFalse(list.isCanonicalAddress(SRC, "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4"), "uppercase Bech32");
        assertFalse(list.isCanonicalAddress(SRC, BTC_TESTNET), "a testnet address");
        assertFalse(list.isCanonicalAddress(SRC, BTC_REGTEST), "a regtest address");
        assertTrue(list.isCanonicalAddress(OTHER_SRC, XRP_C));
        assertFalse(list.isCanonicalAddress(OTHER_SRC, XRP_X_ADDRESS), "an X-address");
        assertFalse(list.isCanonicalAddress(SRC, ""));
    }

    /// On a Testnet deployment the test ids are the supported ones, and their addresses are the testnet ones.
    function testTestnetDeploymentTakesTestIdsAndTestnetAddresses() public {
        ForbiddenAddressList testnetList = _deployList(IExternalNetwork.Network.Testnet);
        assertTrue(testnetList.isCanonicalAddress(bytes32("testBTC"), BTC_TESTNET));
        assertFalse(testnetList.isCanonicalAddress(bytes32("testBTC"), BTC_A), "a mainnet address");
        assertTrue(testnetList.isCanonicalAddress(bytes32("testXRP"), XRP_C));
        vm.expectRevert(abi.encodeWithSelector(IForbiddenAddressList.UnsupportedSourceId.selector, SRC));
        testnetList.isCanonicalAddress(SRC, BTC_A);
        vm.prank(governance);
        testnetList.addForbiddenAddresses(bytes32("testBTC"), _list(BTC_TESTNET));
        assertTrue(testnetList.isForbidden(bytes32("testBTC"), BTC_TESTNET));
    }

    /// A Local deployment stands in for either network, as the simulation's: both kinds of id, regtest addresses.
    function testLocalDeploymentTakesBothIdsAndRegtestAddresses() public {
        ForbiddenAddressList localList = _deployList(IExternalNetwork.Network.Local);
        assertTrue(localList.isCanonicalAddress(SRC, BTC_REGTEST));
        assertTrue(localList.isCanonicalAddress(bytes32("testBTC"), BTC_REGTEST));
        assertFalse(localList.isCanonicalAddress(SRC, BTC_A), "a mainnet address");
        assertFalse(localList.isCanonicalAddress(SRC, BTC_TESTNET), "a testnet Bech32 address");
        assertTrue(localList.isCanonicalAddress(OTHER_SRC, XRP_C));
        assertTrue(localList.isCanonicalAddress(bytes32("testXRP"), XRP_C));
        vm.prank(governance);
        localList.addForbiddenAddresses(SRC, _list(BTC_REGTEST));
        assertTrue(localList.isForbidden(SRC, BTC_REGTEST));
        assertFalse(localList.isForbidden(bytes32("testBTC"), BTC_REGTEST), "a separate list under the other id");
    }

    /// A check by string refuses a spelling that cannot be listed rather than answering it is clean.
    function testIsForbiddenRevertNonCanonicalAddress() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        string memory upper = "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4";
        vm.expectRevert(abi.encodeWithSelector(IForbiddenAddressList.NonCanonicalAddress.selector, SRC, upper));
        list.isForbidden(SRC, upper);
        vm.expectRevert(
            abi.encodeWithSelector(IForbiddenAddressList.NonCanonicalAddress.selector, OTHER_SRC, XRP_X_ADDRESS)
        );
        list.isForbidden(OTHER_SRC, XRP_X_ADDRESS);
        assertTrue(list.isForbidden(SRC, BTC_A));
        assertTrue(list.isForbiddenHash(SRC, keccak256(bytes(BTC_A))), "a hash is not checked");
    }

    // ------------------------------------------------------------ removing

    /// The last entry takes a removed one's place; the version rises; the addition time stays.
    function testGovernanceRemovesAddresses() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B, BTC_C, BTC_D));
        uint64 addedAt = list.lastAdditionTimestamp(SRC);
        skip(1 hours);
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenAddressRemoved(SRC, BTC_B);
        vm.expectEmit();
        emit IForbiddenAddressList.ListVersionChanged(SRC, 2);
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_B, "not listed"));

        assertFalse(list.isForbidden(SRC, BTC_B));
        assertTrue(list.isForbidden(SRC, BTC_D));
        assertEq(list.lastAdditionTimestamp(SRC), addedAt, "a removal does not move it");
        (string[] memory addresses, uint256 total, uint64 version) = list.getForbiddenAddresses(SRC, 0, 10);
        assertEq(total, 3);
        assertEq(version, 2);
        assertEq(addresses[0], BTC_A);
        assertEq(addresses[1], BTC_D, "the last entry moved into the removed one's place");
        assertEq(addresses[2], BTC_C);
        (bytes32[] memory hashes, , ) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(hashes[1], keccak256(bytes(BTC_D)), "the hashes move with the addresses");
    }

    function testRemoveTheLastEntry() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B));
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_B, BTC_A));
        (, uint256 total, uint64 version) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(total, 0);
        assertEq(version, 2);
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_B));
        assertTrue(list.isForbidden(SRC, BTC_B));
    }

    /// A removal that finds nothing changes nothing.
    function testRemovingUnlistedAddressesChangesNothing() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_B));
        (, , uint64 version) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(version, 1);
    }

    function testRemoveRevertMaintainer() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        vm.prank(maintainer);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        list.removeForbiddenAddresses(SRC, _list(BTC_A));
    }

    /// Removing releases value, so in production it waits out the governance timelock.
    function testRemoveIsTimelockedInProduction() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        _switchToProduction();
        bytes memory call = abi.encodeCall(list.removeForbiddenAddresses, (SRC, _list(BTC_A)));
        vm.prank(productionGovernance);
        (bool ok, ) = address(list).call(call);
        assertTrue(ok);
        assertTrue(list.isForbidden(SRC, BTC_A), "must not execute at once");
        skip(TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(list)).executeGovernanceCall(call);
        assertFalse(list.isForbidden(SRC, BTC_A));
    }

    // ------------------------------------------------------------ maintainers

    function testAddMaintainers() public {
        address other = makeAddr("other");
        vm.expectEmit();
        emit IForbiddenAddressList.MaintainersAdded(_maintainers(other));
        vm.prank(governance);
        list.addMaintainers(_maintainers(other));
        assertTrue(list.isMaintainer(other));
        assertTrue(list.isMaintainer(maintainer));
        address[] memory all = list.getMaintainers();
        assertEq(all.length, 2);
        vm.prank(other);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_B));
        assertTrue(list.isForbidden(SRC, BTC_A));
        assertTrue(list.isForbidden(SRC, BTC_B));
    }

    /// Adding a maintainer already in the set leaves it as it is.
    function testAddMaintainersSkipsExisting() public {
        vm.prank(governance);
        list.addMaintainers(_maintainers(maintainer));
        assertEq(list.getMaintainers().length, 1);
    }

    function testAddMaintainersRevertMaintainerZero() public {
        vm.prank(governance);
        vm.expectRevert(IForbiddenAddressList.MaintainerZero.selector);
        list.addMaintainers(_maintainers(address(0)));
    }

    /// Adding a maintainer grants a power, so in production it waits out the governance timelock.
    function testAddMaintainersIsTimelockedInProduction() public {
        _switchToProduction();
        address other = makeAddr("other");
        vm.prank(productionGovernance);
        list.addMaintainers(_maintainers(other));
        assertFalse(list.isMaintainer(other), "must not execute at once");
    }

    /// Removing a maintainer takes effect at once, in production too.
    function testRemoveMaintainersIsImmediateInProduction() public {
        _switchToProduction();
        vm.expectEmit();
        emit IForbiddenAddressList.MaintainersRemoved(_maintainers(maintainer));
        vm.prank(productionGovernance);
        list.removeMaintainers(_maintainers(maintainer));
        assertFalse(list.isMaintainer(maintainer));
        assertEq(list.getMaintainers().length, 0);
        vm.prank(maintainer);
        vm.expectRevert(IForbiddenAddressList.OnlyMaintainerOrImmediateGovernance.selector);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
    }

    function testRemoveMaintainersRevertOnlyGovernance() public {
        vm.prank(maintainer);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        list.removeMaintainers(_maintainers(maintainer));
    }

    function testAddMaintainersRevertOnlyGovernance() public {
        vm.prank(maintainer);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        list.addMaintainers(_maintainers(makeAddr("other")));
    }

    // ------------------------------------------------------------ pagination

    /// Pages cover the list once, each with the total and the version; a page past the end is empty.
    function testPagination() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B, BTC_C, BTC_D));
        (string[] memory first, uint256 total, uint64 version) = list.getForbiddenAddresses(SRC, 0, 3);
        (string[] memory second, uint256 total2, uint64 version2) = list.getForbiddenAddresses(SRC, 3, 3);
        (string[] memory past, uint256 total3, ) = list.getForbiddenAddresses(SRC, 9, 3);
        assertEq(first.length, 3);
        assertEq(second.length, 1);
        assertEq(second[0], BTC_D);
        assertEq(past.length, 0);
        assertEq(total, 4);
        assertEq(total2, 4);
        assertEq(total3, 4);
        assertEq(version2, version, "one list");
        (bytes32[] memory hashes, , ) = list.getForbiddenAddressHashes(SRC, 1, 2);
        assertEq(hashes.length, 2);
        assertEq(hashes[0], keccak256(bytes(BTC_B)));
    }

    /// A change between two pages shows in the version, so the reader knows to start again.
    function testAChangeBetweenPagesRaisesTheVersion() public {
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B, BTC_C));
        (, , uint64 before) = list.getForbiddenAddressHashes(SRC, 0, 2);
        vm.prank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_A));
        (, , uint64 afterwards) = list.getForbiddenAddressHashes(SRC, 2, 2);
        assertGt(afterwards, before);
    }

    function testEmptyList() public view {
        (bytes32[] memory hashes, uint256 total, uint64 version) = list.getForbiddenAddressHashes(SRC, 0, 10);
        assertEq(hashes.length, 0);
        assertEq(total, 0);
        assertEq(version, 0);
        assertEq(list.lastAdditionTimestamp(SRC), 0);
    }

    /// A batch of a hundred real Bitcoin addresses — the longest of the deploy file, Bech32 of 42 and 62 characters —
    /// validated and added, stays well inside Flare's 28M block.
    function testAHundredAddressesFitOneBlock() public {
        string[] memory all = vm.parseJsonStringArray(
            vm.readFile("deployment/chain-config/forbidden-addresses.json"), ".lists[0].addresses"
        );
        string[] memory batch = new string[](100);
        for (uint256 i = 0; i < 100; i++) {
            batch[i] = all[all.length - 100 + i];    // the file is sorted: its Bech32 addresses come last
        }
        vm.prank(maintainer);
        uint256 gasBefore = gasleft();
        list.addForbiddenAddresses(SRC, batch);
        uint256 used = gasBefore - gasleft();
        emit log_named_uint("gas for 100 additions", used);
        assertLt(used, 20_000_000);
        (, uint256 total, ) = list.getForbiddenAddressHashes(SRC, 0, 0);
        assertEq(total, 100);
    }

    // ------------------------------------------------------------ the EVM list

    function testMaintainerAddsEvmAddresses() public {
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenEvmAddressAdded(EVM_A);
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenEvmAddressAdded(EVM_B);
        vm.expectEmit();
        emit IForbiddenAddressList.EvmListVersionChanged(1);
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A, EVM_B));

        assertTrue(list.isForbiddenEvmAddress(EVM_A));
        assertTrue(list.isForbiddenEvmAddress(EVM_B));
        assertFalse(list.isForbiddenEvmAddress(EVM_C));
        assertEq(list.getEvmVersion(), 1);
        assertEq(list.lastEvmAdditionTimestamp(), block.timestamp);
        (address[] memory page, uint256 total, uint64 version) = list.getForbiddenEvmAddresses(0, 10);
        assertEq(total, 2);
        assertEq(version, 1);
        assertEq(page.length, 2);
        assertEq(page[0], EVM_A);
        assertEq(page[1], EVM_B);
    }

    /// Adding is immediate for governance even in production mode, as on the source lists.
    function testGovernanceAddsEvmAddressesAtOnceInProduction() public {
        _switchToProduction();
        vm.prank(productionGovernance);
        list.addForbiddenEvmAddresses(_evm(EVM_A));
        assertTrue(list.isForbiddenEvmAddress(EVM_A));
    }

    /// A batch that only repeats listed addresses changes nothing: no event, no version, no new addition time.
    function testRepeatedEvmAddressesAreSkipped() public {
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A, EVM_B));
        skip(1 days);
        vm.recordLogs();
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_B, EVM_A));
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(list.getEvmVersion(), 1);
        assertEq(list.lastEvmAdditionTimestamp(), block.timestamp - 1 days);
    }

    function testAddEvmRevertEvmAddressZero() public {
        vm.prank(maintainer);
        vm.expectRevert(IForbiddenAddressList.EvmAddressZero.selector);
        list.addForbiddenEvmAddresses(_evm(EVM_A, address(0)));
    }

    function testAddEvmRevertOnlyMaintainerOrImmediateGovernance() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IForbiddenAddressList.OnlyMaintainerOrImmediateGovernance.selector);
        list.addForbiddenEvmAddresses(_evm(EVM_A));
    }

    /// The EVM list is apart from every source's list: a change to one moves neither the other's entries nor version.
    function testTheEvmListIsApartFromTheSourceLists() public {
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertEq(list.getEvmVersion(), 1);
        assertEq(list.getVersion(SRC), 1);
        vm.expectRevert(abi.encodeWithSelector(IForbiddenAddressList.UnsupportedSourceId.selector, bytes32("ETH")));
        list.isCanonicalAddress(bytes32("ETH"), "0x8589427373d6d84e98730d7795d8f6f8731fda16");
        (, uint256 total, ) = list.getForbiddenEvmAddresses(0, 10);
        assertEq(total, 1);
    }

    /// The last entry takes a removed one's place; the version rises; the addition time stays.
    function testGovernanceRemovesEvmAddresses() public {
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A, EVM_B, EVM_C));
        uint64 addedAt = list.lastEvmAdditionTimestamp();
        skip(1 hours);
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenEvmAddressRemoved(EVM_A);
        vm.expectEmit();
        emit IForbiddenAddressList.EvmListVersionChanged(2);
        vm.prank(governance);
        list.removeForbiddenEvmAddresses(_evm(EVM_A, makeAddr("unlisted")));
        assertFalse(list.isForbiddenEvmAddress(EVM_A));
        (address[] memory page, uint256 total, uint64 version) = list.getForbiddenEvmAddresses(0, 10);
        assertEq(total, 2);
        assertEq(version, 2);
        assertEq(page[0], EVM_C, "the last entry moved into the gap");
        assertEq(page[1], EVM_B);
        assertEq(list.lastEvmAdditionTimestamp(), addedAt);

        vm.recordLogs();
        vm.prank(governance);
        list.removeForbiddenEvmAddresses(_evm(EVM_A));
        assertEq(vm.getRecordedLogs().length, 0, "removing an unlisted address changes nothing");
        assertEq(list.getEvmVersion(), 2);
    }

    function testRemoveEvmRevertMaintainer() public {
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A));
        vm.prank(maintainer);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        list.removeForbiddenEvmAddresses(_evm(EVM_A));
    }

    /// Removing releases value, so in production it waits out the governance timelock.
    function testRemoveEvmIsTimelockedInProduction() public {
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A));
        _switchToProduction();
        bytes memory call = abi.encodeCall(list.removeForbiddenEvmAddresses, (_evm(EVM_A)));
        vm.prank(productionGovernance);
        (bool ok, ) = address(list).call(call);
        assertTrue(ok);
        assertTrue(list.isForbiddenEvmAddress(EVM_A), "must not execute at once");
        skip(TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(list)).executeGovernanceCall(call);
        assertFalse(list.isForbiddenEvmAddress(EVM_A));
    }

    /// Pages cover the list once, each with the total and the version; a page at or past the end is empty.
    function testEvmPagination() public {
        (address[] memory empty, uint256 none, uint64 zero) = list.getForbiddenEvmAddresses(0, 10);
        assertEq(empty.length, 0);
        assertEq(none, 0);
        assertEq(zero, 0);
        assertEq(list.lastEvmAdditionTimestamp(), 0);
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(EVM_A, EVM_B, EVM_C));
        (address[] memory first, uint256 total, uint64 version) = list.getForbiddenEvmAddresses(0, 2);
        (address[] memory second, , uint64 version2) = list.getForbiddenEvmAddresses(2, 2);
        (address[] memory atEnd, , ) = list.getForbiddenEvmAddresses(3, 2);
        (address[] memory past, uint256 total3, ) = list.getForbiddenEvmAddresses(9, 2);
        assertEq(first.length, 2);
        assertEq(second.length, 1);
        assertEq(second[0], EVM_C);
        assertEq(atEnd.length, 0);
        assertEq(past.length, 0);
        assertEq(total, 3);
        assertEq(total3, 3);
        assertEq(version2, version, "one list");
    }

    /// An EVM entry is two storage slots and no string: a hundred cost a fraction of a hundred strings.
    function testAHundredEvmAddressesFitOneBlock() public {
        address[] memory batch = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            batch[i] = address(uint160(uint256(keccak256(abi.encode(i)))));
        }
        vm.prank(maintainer);
        uint256 gasBefore = gasleft();
        list.addForbiddenEvmAddresses(batch);
        uint256 used = gasBefore - gasleft();
        emit log_named_uint("gas for 100 EVM additions", used);
        assertLt(used, 6_000_000);
        (, uint256 total, ) = list.getForbiddenEvmAddresses(0, 0);
        assertEq(total, 100);
    }
}

contract ForbiddenAddressListPersonalAccountTest is ForbiddenAddressListTestBase {

    function testANewlyAddedOwnerListsItsPersonalAccount() public {
        address provider = address(new DerivingProvider());
        vm.prank(governance);
        list.setPersonalAccountProvider(SRC, provider);
        assertEq(list.getPersonalAccountProvider(SRC), provider);

        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenAddressAdded(SRC, BTC_A);
        vm.expectEmit();
        emit IForbiddenAddressList.ForbiddenEvmAddressAdded(_pa(BTC_A));
        vm.expectEmit();
        emit IForbiddenAddressList.PersonalAccountDerived(SRC, BTC_A, _pa(BTC_A));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A, BTC_B));

        assertTrue(list.isForbiddenEvmAddress(_pa(BTC_A)));
        assertTrue(list.isForbiddenEvmAddress(_pa(BTC_B)));
        assertEq(list.getEvmVersion(), 1, "one EVM version for the call");
        assertEq(list.lastEvmAdditionTimestamp(), block.timestamp);
        assertEq(list.getVersion(SRC), 1);
    }

    /// A provider is per source: another source's additions derive nothing.
    function testAProviderServesOnlyItsSource() public {
        _setProvider(OTHER_SRC, address(new DerivingProvider()));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertFalse(list.isForbiddenEvmAddress(_pa(BTC_A)));
        assertEq(list.getEvmVersion(), 0);
    }

    /// A repeated owner is skipped together with its derivation: a Personal Account governance removed while its
    /// owner stays listed is not listed again by a resubmitted batch.
    function testARepeatSkipsTheDerivation() public {
        _setProvider(SRC, address(new DerivingProvider()));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        vm.prank(governance);
        list.removeForbiddenEvmAddresses(_evm(_pa(BTC_A)));
        vm.recordLogs();
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertEq(vm.getRecordedLogs().length, 0, "nothing happens");
        assertFalse(list.isForbiddenEvmAddress(_pa(BTC_A)));
    }

    /// A removal never cascades; an owner removed and added again counts as new and derives again.
    function testRemovalDoesNotCascadeAndAReaddDerivesAgain() public {
        _setProvider(SRC, address(new DerivingProvider()));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        vm.startPrank(governance);
        list.removeForbiddenAddresses(SRC, _list(BTC_A));
        assertTrue(list.isForbiddenEvmAddress(_pa(BTC_A)), "the Personal Account stays");
        list.removeForbiddenEvmAddresses(_evm(_pa(BTC_A)));
        vm.stopPrank();
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertTrue(list.isForbiddenEvmAddress(_pa(BTC_A)), "derived again");
    }

    /// An owner whose Personal Account is already on the EVM list is reported as derived; the EVM list does not move.
    function testAnAlreadyListedPersonalAccountIsNotAddedTwice() public {
        _setProvider(SRC, address(new DerivingProvider()));
        vm.prank(maintainer);
        list.addForbiddenEvmAddresses(_evm(_pa(BTC_A)));
        vm.expectEmit();
        emit IForbiddenAddressList.PersonalAccountDerived(SRC, BTC_A, _pa(BTC_A));
        vm.prank(maintainer);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertEq(list.getEvmVersion(), 1, "the EVM list did not change");
    }

    /// The provider is a governed contract trusted to answer: if it reverts or answers zero, the addition reverts and
    /// lists nothing, rather than listing an owner without its Personal Account.
    function testAFailingProviderRevertsTheAddition() public {
        _setProvider(SRC, address(new RevertingProvider()));
        vm.prank(maintainer);
        vm.expectRevert(bytes("no account"));
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        _setProvider(SRC, address(new ZeroProvider()));
        vm.prank(maintainer);
        vm.expectRevert(IForbiddenAddressList.EvmAddressZero.selector);
        list.addForbiddenAddresses(SRC, _list(BTC_A));
        assertFalse(list.isForbidden(SRC, BTC_A));
        assertEq(list.getVersion(SRC), 0);
    }

    /// Setting and clearing a provider both wait out the governance timelock: a provider decides what is frozen, and
    /// clearing it lets a Personal Account go unlisted.
    function testSetPersonalAccountProviderIsTimelockedBothWays() public {
        address provider = address(new DerivingProvider());
        _switchToProduction();
        bytes memory set = abi.encodeCall(list.setPersonalAccountProvider, (SRC, provider));
        vm.prank(productionGovernance);
        (bool ok, ) = address(list).call(set);
        assertTrue(ok);
        assertEq(list.getPersonalAccountProvider(SRC), address(0), "must not execute at once");
        skip(TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(list)).executeGovernanceCall(set);
        assertEq(list.getPersonalAccountProvider(SRC), provider);

        bytes memory clear = abi.encodeCall(list.setPersonalAccountProvider, (SRC, address(0)));
        vm.prank(productionGovernance);
        (ok, ) = address(list).call(clear);
        assertTrue(ok);
        assertEq(list.getPersonalAccountProvider(SRC), provider, "clearing waits too");
        skip(TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(list)).executeGovernanceCall(clear);
        assertEq(list.getPersonalAccountProvider(SRC), address(0));
    }

    function testSetPersonalAccountProviderReverts() public {
        address provider = address(new DerivingProvider());
        address noCode = makeAddr("no code");
        vm.prank(maintainer);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        list.setPersonalAccountProvider(SRC, provider);
        vm.prank(governance);
        vm.expectRevert(IForbiddenAddressList.PersonalAccountProviderWithoutCode.selector);
        list.setPersonalAccountProvider(SRC, noCode);
        vm.prank(governance);
        vm.expectRevert(abi.encodeWithSelector(IForbiddenAddressList.UnsupportedSourceId.selector, bytes32("ETH")));
        list.setPersonalAccountProvider(bytes32("ETH"), provider);
    }

    /// A hundred real Bitcoin addresses, each with its Personal Account derived and listed, still fit a Flare block
    /// (28M). The smart-account controller's derivation costs about 12k gas a call, some 1M more for the batch than
    /// this provider's.
    function testAHundredAddressesWithPersonalAccountsFitOneBlock() public {
        _setProvider(SRC, address(new DerivingProvider()));
        string[] memory all = vm.parseJsonStringArray(
            vm.readFile("deployment/chain-config/forbidden-addresses.json"), ".lists[0].addresses"
        );
        string[] memory batch = new string[](100);
        for (uint256 i = 0; i < 100; i++) {
            batch[i] = all[all.length - 100 + i];
        }
        vm.prank(maintainer);
        uint256 gasBefore = gasleft();
        list.addForbiddenAddresses(SRC, batch);
        uint256 used = gasBefore - gasleft();
        emit log_named_uint("gas for 100 additions with Personal Accounts", used);
        assertLt(used, 21_000_000);
        (, uint256 total, ) = list.getForbiddenEvmAddresses(0, 0);
        assertEq(total, 100);
    }
}
