// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {RelayDeployBase} from "../../../deployment/scripts/relay/RelayDeployBase.s.sol";
import {Create3Factory} from "../../../contracts/utils/implementation/Create3Factory.sol";

/// Concrete handle exposing the deploy base's internal helpers/constants to the test.
contract RelayDeployBaseHarness is RelayDeployBase {
    function factoryAddress() external pure returns (address) {
        return _factoryAddress();
    }

    function frozenInitCode() external view returns (bytes memory) {
        return _frozenFactoryInitCode();
    }

    function arachnid() external pure returns (address) {
        return ARACHNID_CREATE2_DEPLOYER;
    }

    function factorySalt() external pure returns (bytes32) {
        return FACTORY_CREATE2_SALT;
    }

    function initcodeKeccak() external pure returns (bytes32) {
        return FACTORY_INITCODE_KECCAK;
    }

    function relayProxySaltBase() external pure returns (bytes32) {
        return RELAY_PROXY_SALT_BASE;
    }

    function relayProxySalt(uint256 _sourceChainId) external pure returns (bytes32) {
        return _relayProxySalt(_sourceChainId);
    }

    function readDeployedAddress(string calldata _network, string calldata _name)
        external view
        returns (address)
    {
        return _readDeployedAddress(_network, _name);
    }
}

/**
 * Pins the frozen Create3Factory initcode and the canonical addresses/salts the cross-chain
 * Relay deployment depends on. Any accidental drift (a recompile that changes the factory
 * bytecode, an edited frozen file, a changed salt label) fails here — see
 * deployment/create3/README.md.
 */
contract RelayDeployAddressTest is Test {
    // Canonical values documented in deployment/create3/README.md.
    address internal constant CANONICAL_FACTORY = 0x51a24B38b2a5793F65258Fd37EE92706FadeFE96;
    bytes32 internal constant CANONICAL_INITCODE_KECCAK =
        0x527b93054ed37ffa9db40d5b403b0c72aa7b5c50cd28a0e344a25684fbe0f567;

    RelayDeployBaseHarness internal harness;

    function setUp() public {
        harness = new RelayDeployBaseHarness();
    }

    function test_frozenInitCodeMatchesCompiledFactory() public view {
        // The committed frozen bytes currently equal the compiled Create3Factory creation code.
        // If a compiler/settings change breaks this, DO NOT silently regenerate the frozen file:
        // that moves the factory address on every not-yet-deployed chain. Decide deliberately
        // (see deployment/create3/README.md), then update the frozen file, the pin and this test.
        assertEq(
            keccak256(type(Create3Factory).creationCode),
            CANONICAL_INITCODE_KECCAK,
            "compiled Create3Factory creation code drifted from the frozen pin"
        );
    }

    function test_frozenFileMatchesPin() public view {
        // _frozenFactoryInitCode() itself asserts the file hash == FACTORY_INITCODE_KECCAK.
        assertEq(keccak256(harness.frozenInitCode()), CANONICAL_INITCODE_KECCAK);
        assertEq(harness.initcodeKeccak(), CANONICAL_INITCODE_KECCAK);
    }

    function test_canonicalFactoryAddress() public view {
        // _factoryAddress() == CREATE2(Arachnid, salt, initcodeHash) == the documented address.
        address computed = address(uint160(uint256(keccak256(abi.encodePacked(
            hex"ff", harness.arachnid(), harness.factorySalt(), harness.initcodeKeccak()
        )))));
        assertEq(harness.factoryAddress(), computed);
        assertEq(harness.factoryAddress(), CANONICAL_FACTORY);
    }

    function test_readsDeployedAddressFromCommittedDeploysJson() public view {
        // Confirms the persistent deploys-registry reader parses the committed
        // deployment/deploys/<network>.json format (stdJson struct field order). PrepareRelaySourceSnapshot
        // reads the latest Relay from here rather than a transient manifest.
        assertEq(
            harness.readDeployedAddress("flare", "Relay"),
            0xCcF30790A93F15e24EB909548a2C58a9b0a7FBd4
        );
        assertEq(harness.readDeployedAddress("flare", "NoSuchContract"), address(0));
    }

    function test_saltLabelsPinned() public view {
        assertEq(harness.factorySalt(), keccak256("flare.create3-factory.v1"));
        assertEq(harness.relayProxySaltBase(), keccak256("flare.relay-proxy.v1"));
    }

    function test_relayProxySaltIsSourceScoped() public view {
        bytes32 base = keccak256("flare.relay-proxy.v1");
        // Salt (and hence Relay address) is per source chain.
        assertEq(harness.relayProxySalt(14), keccak256(abi.encode(base, uint256(14))));
        assertEq(harness.relayProxySalt(19), keccak256(abi.encode(base, uint256(19))));
        // Different sources ⇒ different salts ⇒ a chain can host a home + cross-source mirror.
        assertTrue(harness.relayProxySalt(14) != harness.relayProxySalt(19));
    }

    function test_create3AddressIsInitcodeIndependent() public {
        // The factory's CREATE3 address depends only on (factory, deployer, salt) — not on the
        // deployed initcode. This is what makes the mirror address reusable across chains.
        Create3Factory factory = new Create3Factory();
        address deployer = address(0xD1);
        bytes32 salt = keccak256("test-salt");
        address predicted = factory.computeAddress(deployer, salt);

        vm.prank(deployer);
        address deployed = factory.deploy(salt, type(Create3Factory).creationCode);
        assertEq(deployed, predicted, "CREATE3 address must match computeAddress regardless of initcode");

        // A different deployer with the same salt gets a different address (deployer-scoped salt).
        assertTrue(factory.computeAddress(address(0xD2), salt) != predicted);
    }
}
