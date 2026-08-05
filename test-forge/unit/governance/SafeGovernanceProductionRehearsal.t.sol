// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// solhint-disable func-name-mixedcase, no-inline-assembly

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {ISafeGovernance} from "../../../contracts/userInterfaces/ISafeGovernance.sol";
import {SafeGovernance} from "../../../contracts/governance/lib/SafeGovernance.sol";
import {SafeInstructions} from "../../../contracts/governance/implementation/SafeInstructions.sol";
import {SafeInstructionsProxy} from "../../../contracts/governance/implementation/SafeInstructionsProxy.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

interface IProductionShapeSafe {
    function VERSION() external view returns (string memory);

    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes32);

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

contract SafeGovernanceProductionRehearsalTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant CHAIN_A = 100;
    uint256 internal constant CHAIN_B = 200;
    uint256 internal constant OWNER_COUNT = 11;
    uint256 internal constant THRESHOLD = 6;
    uint256 internal constant FLARE_BLOCK_GAS_LIMIT = 28_000_000;
    uint256 internal constant OPERATIONAL_GAS_LIMIT = FLARE_BLOCK_GAS_LIMIT * 80 / 100;
    address internal constant SENTINEL_OWNERS = address(0x1);
    address internal constant PRODUCTION_FALLBACK_HANDLER = 0x3f083d314C01aD7f1cc53B0a8422EE335CF2923a;
    bytes32 internal constant PRODUCTION_SINGLETON_RUNTIME_HASH =
        0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f;
    bytes32 internal constant PRODUCTION_PROXY_RUNTIME_HASH =
        0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000;
    bytes32 internal constant PRODUCTION_FALLBACK_RUNTIME_HASH =
        0x03e69f7ce809e81687c69b19a7d7cca45b6d551ffdec73d9bb87178476de1abf;
    string internal constant SAFE_ARTIFACT_ROOT =
        "node_modules/@gnosis.pm/safe-contracts/build/artifacts/contracts/";
    string internal constant SINGLETON_ARTIFACT = "GnosisSafeL2.sol/GnosisSafeL2.json";
    string internal constant PROXY_ARTIFACT = "proxies/GnosisSafeProxy.sol/GnosisSafeProxy.json";
    string internal constant FALLBACK_ARTIFACT =
        "handler/CompatibilityFallbackHandler.sol/CompatibilityFallbackHandler.json";
    bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 internal constant FALLBACK_HANDLER_STORAGE_SLOT =
        0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
    bytes4 internal constant CHANGE_FEES =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,address,uint8,uint256)[])"));

    IProductionShapeSafe internal safe;
    address internal singleton;
    SafeInstructions internal checker;
    Relay internal relayA;
    Relay internal relayB;
    uint256[] internal ownerKeys;
    address[] internal owners;
    bytes32 internal ownerHash;

    function setUp() public {
        vm.chainId(SOURCE_CHAIN);
        uint256[] memory initialKeys = new uint256[](OWNER_COUNT);
        for (uint256 i; i < OWNER_COUNT; ++i) {
            initialKeys[i] = 1_001 + i;
        }
        _sortKeys(initialKeys);
        ownerKeys = initialKeys;
        owners = _owners(ownerKeys);

        singleton = _deployReleaseArtifact(string.concat(SAFE_ARTIFACT_ROOT, SINGLETON_ARTIFACT), bytes(""));
        address proxy = _deployReleaseArtifact(
            string.concat(SAFE_ARTIFACT_ROOT, PROXY_ARTIFACT), abi.encode(singleton)
        );
        vm.etch(
            PRODUCTION_FALLBACK_HANDLER,
            _releaseRuntime(string.concat(SAFE_ARTIFACT_ROOT, FALLBACK_ARTIFACT))
        );
        safe = IProductionShapeSafe(proxy);
        safe.setup(
            owners, THRESHOLD, address(0), bytes(""), PRODUCTION_FALLBACK_HANDLER, address(0), 0, payable(address(0))
        );
        SafeInstructions checkerImplementation = new SafeInstructions();
        checker = SafeInstructions(
            address(
                new SafeInstructionsProxy(
                    IGovernanceSettings(makeAddr("governanceSettings")),
                    makeAddr("flareGovernance"),
                    makeAddr("addressUpdater"),
                    address(checkerImplementation),
                    address(safe)
                )
            )
        );
        // initialize admits the live Safe configuration as generation 0 — no bootstrap
        // transaction exists; the fresh Safe's first signed nonce (0) is a relayable action.
        ownerHash = checker.activeOwnerConfigHash();

        vm.chainId(CHAIN_A);
        relayA = _deployRelay(_relayConfig());
        vm.chainId(CHAIN_B);
        relayB = _deployRelay(_relayConfig());
    }

    function test_rehearsalMatchesFlareSafeVersionAndConfigurationShape() public view {
        assertEq(safe.VERSION(), "1.3.0");
        assertEq(singleton.codehash, PRODUCTION_SINGLETON_RUNTIME_HASH);
        assertEq(address(safe).codehash, PRODUCTION_PROXY_RUNTIME_HASH);
        assertEq(PRODUCTION_FALLBACK_HANDLER.codehash, PRODUCTION_FALLBACK_RUNTIME_HASH);
        assertEq(safe.getOwners().length, OWNER_COUNT);
        assertEq(safe.getThreshold(), THRESHOLD);

        (address[] memory modules, address next) = safe.getModulesPaginated(SENTINEL_OWNERS, 100);
        assertEq(modules.length, 0);
        assertEq(next, SENTINEL_OWNERS);

        bytes memory guardWord = safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1);
        bytes memory fallbackWord = safe.getStorageAt(uint256(FALLBACK_HANDLER_STORAGE_SLOT), 1);
        assertEq(abi.decode(guardWord, (address)), address(0));
        assertEq(abi.decode(fallbackWord, (address)), PRODUCTION_FALLBACK_HANDLER);
    }

    function test_rehearsalExecutesFeesRotationAndFeesThroughRealSafe() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory firstFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(101, 102, 201));
        (ISafeGovernance.SafeTx memory firstFeeTx, bytes memory firstFeeSignatures,) =
            _executeSafe(address(checker), firstFeeAction, ownerKeys);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(firstFeeTx, firstFeeSignatures);
        assertEq(relayA.protocolFeeInWei(3), 101);
        assertEq(relayA.protocolFeeInWei(7), 102);
        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(firstFeeTx, firstFeeSignatures);
        assertEq(relayB.protocolFeeInWei(3), 201);

        vm.chainId(SOURCE_CHAIN);
        address oldOwner = safe.getOwners()[0];
        uint256 replacementKey = 2_000;
        address newOwner = vm.addr(replacementKey);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        // Attest-after ceremony: the Safe rotates natively first (signed by the old set)...
        bytes memory nativeSwap =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeSafe(address(safe), nativeSwap, ownerKeys);
        uint256[] memory newOwnerKeys = _replaceOwnerKey(ownerKeys, oldOwner, replacementKey);
        assertFalse(checker.activeOwnerConfigurationIsLive());

        // ...then the old ∩ new intersection attests the live configuration (10 of 11
        // owners are common; the threshold-6 attestation is valid for the rotated Safe
        // AND for every target still holding the old mirror).
        uint256 rotationNonce = safe.nonce();
        bytes memory rotationAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        (ISafeGovernance.SafeTx memory rotationTx, bytes memory rotationSignatures,) =
            _executeSafe(address(checker), rotationAction, _keysExcludingOwner(ownerKeys, oldOwner));
        bytes32 newOwnerHash = checker.activeOwnerConfigHash();
        assertTrue(checker.activeOwnerConfigurationIsLive());

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(rotationTx, rotationSignatures);
        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(rotationTx, rotationSignatures);
        (bytes32 hashA,) = relayA.governanceOwnerConfig();
        (bytes32 hashB,) = relayB.governanceOwnerConfig();
        assertEq(hashA, newOwnerHash);
        assertEq(hashB, newOwnerHash);

        vm.chainId(SOURCE_CHAIN);

        bytes memory secondFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), newOwnerHash, _feeUpdates(301, 302, 401));
        (ISafeGovernance.SafeTx memory secondFeeTx, bytes memory secondFeeSignatures,) =
            _executeSafe(address(checker), secondFeeAction, newOwnerKeys);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(secondFeeTx, secondFeeSignatures);
        assertEq(relayA.protocolFeeInWei(3), 301);
        assertEq(relayA.protocolFeeInWei(7), 302);
        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(secondFeeTx, secondFeeSignatures);
        assertEq(relayB.protocolFeeInWei(3), 401);
    }

    function test_rehearsalMaximumBatchFitsRecordedFlareBlockGasLimit() public {
        vm.chainId(SOURCE_CHAIN);
        // protocolId is uint8, so the maximum strictly-increasing (canonical) single-deployment
        // batch is protocol ids 2..255 = 254 entries.
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](254);
        for (uint256 i; i < updates.length; ++i) {
            updates[i] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), uint8(i + 2), i + 1);
        }
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, updates);
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures, uint256 sourceGas) =
            _executeSafe(address(checker), action, ownerKeys);
        assertLt(sourceGas, OPERATIONAL_GAS_LIMIT, "source Safe/checker gas budget");

        vm.chainId(CHAIN_A);
        uint256 gasBefore = gasleft();
        relayA.processSafeMessage(txData, signatures);
        uint256 targetGas = gasBefore - gasleft();
        assertLt(targetGas, OPERATIONAL_GAS_LIMIT, "target Relay gas budget");
        assertEq(relayA.protocolFeeInWei(2), 1);
        assertEq(relayA.protocolFeeInWei(255), 254);
    }

    function _deployRelay(IRelay.RelayInitialConfig memory config) internal returns (Relay) {
        Relay relayImplementation = new Relay();
        return Relay(
            address(
                new RelayProxy(address(relayImplementation), config, address(0), IRelay(address(0)), address(this))
            )
        );
    }

    function _relayConfig() internal view returns (IRelay.RelayInitialConfig memory config) {
        config.initialRewardEpochId = 1;
        config.startingVotingRoundIdForInitialRewardEpochId = 1;
        config.initialSigningPolicyHash = bytes32(uint256(1));
        config.randomNumberProtocolId = 2;
        config.firstVotingRoundStartTs = 1;
        config.votingEpochDurationSeconds = 1;
        config.firstRewardEpochStartVotingRoundId = 0;
        config.rewardEpochDurationInVotingEpochs = 1;
        config.thresholdIncreaseBIPS = 10_000;
        config.messageFinalizationWindowInRewardEpochs = 1;
        config.feeCollectionAddress = payable(address(0xFEE));
        config.governance.sourceChainId = SOURCE_CHAIN;
        config.governance.safe = address(safe);
        config.governance.threshold = THRESHOLD;
        config.governance.owners = owners;
        // Generation 0 is admitted from the live Safe at initialize; the floor (first
        // accepted signed nonce) is the fresh Safe's live nonce at deployment.
        config.governance.ownerConfigSafeNonce = 0;
        config.governance.safeNonce = 0;
    }

    function _feeUpdates(uint256 feeA3, uint256 feeA7, uint256 feeB3)
        internal
        view
        returns (SafeGovernance.GovernanceFeeUpdate[] memory updates)
    {
        updates = new SafeGovernance.GovernanceFeeUpdate[](3);
        updates[0] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), 3, feeA3);
        updates[1] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), 7, feeA7);
        updates[2] = SafeGovernance.GovernanceFeeUpdate(CHAIN_B, address(relayB), 3, feeB3);
    }

    function _executeSafe(address to, bytes memory data, uint256[] memory signingKeys)
        internal
        returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures, uint256 gasUsed)
    {
        txData.to = to;
        txData.data = data;
        txData.nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            txData.to,
            txData.value,
            txData.data,
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            txData.refundReceiver,
            txData.nonce
        );
        for (uint256 i; i < THRESHOLD; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKeys[i], digest);
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
        uint256 gasBefore = gasleft();
        assertTrue(
            safe.execTransaction(
                txData.to,
                txData.value,
                txData.data,
                txData.operation,
                txData.safeTxGas,
                txData.baseGas,
                txData.gasPrice,
                txData.gasToken,
                payable(txData.refundReceiver),
                signatures
            )
        );
        gasUsed = gasBefore - gasleft();
    }

    function _deployReleaseArtifact(string memory artifactPath, bytes memory constructorArgs)
        internal
        returns (address deployed)
    {
        bytes memory artifact = vm.parseJsonBytes(vm.readFile(artifactPath), ".bytecode");
        bytes memory creationCode = bytes.concat(artifact, constructorArgs);
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(deployed != address(0), "release artifact deployment failed");
    }

    function _releaseRuntime(string memory artifactPath) internal view returns (bytes memory) {
        return vm.parseJsonBytes(vm.readFile(artifactPath), ".deployedBytecode");
    }

    function _owners(uint256[] memory keys) internal returns (address[] memory values) {
        values = new address[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            values[i] = vm.addr(keys[i]);
        }
    }

    function _sortKeys(uint256[] memory keys) internal {
        for (uint256 i = 1; i < keys.length; ++i) {
            uint256 key = keys[i];
            address owner = vm.addr(key);
            uint256 j = i;
            while (j > 0 && vm.addr(keys[j - 1]) > owner) {
                keys[j] = keys[j - 1];
                --j;
            }
            keys[j] = key;
        }
    }

    function _replaceOwner(address[] memory currentOwners, address oldOwner, address newOwner)
        internal
        pure
        returns (address[] memory result)
    {
        result = new address[](currentOwners.length);
        bool replaced;
        for (uint256 i; i < currentOwners.length; ++i) {
            result[i] = currentOwners[i] == oldOwner ? newOwner : currentOwners[i];
            if (currentOwners[i] == oldOwner) replaced = true;
        }
        require(replaced, "old owner not found");
        for (uint256 i = 1; i < result.length; ++i) {
            address value = result[i];
            uint256 j = i;
            while (j > 0 && result[j - 1] > value) {
                result[j] = result[j - 1];
                --j;
            }
            result[j] = value;
        }
    }

    /// Keys of the old ∩ new intersection after removing one owner — the signer set a
    /// rotation attestation must use (valid on the rotated Safe AND on old-mirror targets).
    function _keysExcludingOwner(uint256[] memory currentKeys, address excludedOwner)
        internal
        returns (uint256[] memory result)
    {
        result = new uint256[](currentKeys.length - 1);
        uint256 position;
        for (uint256 i; i < currentKeys.length; ++i) {
            if (vm.addr(currentKeys[i]) == excludedOwner) continue;
            result[position++] = currentKeys[i];
        }
        require(position == result.length, "owner to exclude not found");
    }

    function _replaceOwnerKey(uint256[] memory currentKeys, address oldOwner, uint256 newKey)
        internal
        returns (uint256[] memory result)
    {
        result = new uint256[](currentKeys.length);
        bool replaced;
        for (uint256 i; i < currentKeys.length; ++i) {
            if (vm.addr(currentKeys[i]) == oldOwner) {
                result[i] = newKey;
                replaced = true;
            } else {
                result[i] = currentKeys[i];
            }
        }
        require(replaced, "old owner key not found");
        _sortKeys(result);
    }
}
